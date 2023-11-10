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

// Adds a record to the register by the passed structure values.
Procedure AddRecord(RecordStructure) Export
	
	BeginTransaction();
	Try
		DataExchangeInternal.AddRecordToInformationRegister(RecordStructure, "DataExchangeTransportSettings");
		
		WritePassword("COMUserPassword", "COMUserPassword", RecordStructure);
		WritePassword("FTPConnectionPassword", "FTPConnectionPassword", RecordStructure);
		WritePassword("ArchivePasswordExchangeMessages", "ArchivePasswordExchangeMessages", RecordStructure);
		
		WSRememberPassword = Undefined;
		If RecordStructure.Property("WSRememberPassword", WSRememberPassword)
			And WSRememberPassword = True Then
			WritePassword("WSPassword", "WSPassword", RecordStructure);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Updates a register record by the passed structure values.
Procedure UpdateRecord(RecordStructure) Export
	
	BeginTransaction();
	Try
		DataExchangeInternal.UpdateInformationRegisterRecord(RecordStructure, "DataExchangeTransportSettings");
		
		WritePassword("COMUserPassword", "COMUserPassword", RecordStructure);
		WritePassword("FTPConnectionPassword", "FTPConnectionPassword", RecordStructure);
		WritePassword("WSPassword", "WSPassword", RecordStructure);
		WritePassword("ArchivePasswordExchangeMessages", "ArchivePasswordExchangeMessages", RecordStructure);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// For internal use.
// 
Function TransportSettingsWS(Peer, AuthenticationParameters = Undefined) Export
	
	SetPrivilegedMode(True);
	
	SettingsStructure = ExchangeTransportSettingsContent("WS");
	Result = GetRegisterDataByStructure(Peer, SettingsStructure);
	
	Result.Insert("SourceInfobaseID", "");
	
	If ValueIsFilled(Result.WSCorrespondentEndpoint) Then
		
		ModuleMessagesExchangeTransportSettings = Common.CommonModule("InformationRegisters.MessageExchangeTransportSettings");
		Settings = ModuleMessagesExchangeTransportSettings.TransportSettingsWS(Result.WSCorrespondentEndpoint);
		
		Result.Insert("WSPassword");
		FillPropertyValues(Result, Settings);
		Return Result;
			
	EndIf;
	
	WSPassword = Common.ReadDataFromSecureStorage(Peer, "WSPassword");
	SetPrivilegedMode(False);
	
	If TypeOf(WSPassword) = Type("String")
		Or WSPassword = Undefined Then
		
		Result.Insert("WSPassword", WSPassword);
	Else
		Raise NStr("en = 'An error occurred while extracting a password from a secure storage.';");
	EndIf;
	
	If TypeOf(AuthenticationParameters) = Type("Structure") Then // Initializing exchange using the current user name.
		
		If AuthenticationParameters.UseCurrentUser Then
			
			Result.WSUserName = InfoBaseUsers.CurrentUser().Name;
			
		EndIf;
		
		Password = Undefined;
		
		If AuthenticationParameters.Property("Password", Password)
			And Password <> Undefined Then // 
			
			Result.WSPassword = Password;
			
		Else // 
			
			Password = DataExchangeServer.DataSynchronizationPassword(Peer);
			
			Result.WSPassword = ?(Password = Undefined, "", Password);
			
		EndIf;
		
	ElsIf TypeOf(AuthenticationParameters) = Type("String") Then
		Result.WSPassword = AuthenticationParameters;
	EndIf;
	
	Return Result;
EndFunction

Function ExternalSystemTransportSettings(Peer) Export
	
	Query = New Query(
	"SELECT
	|	DataExchangeTransportSettings.ExternalSystemConnectionParameters AS ExternalSystemConnectionParameters
	|FROM
	|	InformationRegister.DataExchangeTransportSettings AS DataExchangeTransportSettings
	|WHERE
	|	DataExchangeTransportSettings.Peer = &Peer
	|	AND DataExchangeTransportSettings.DefaultExchangeMessagesTransportKind = &DefaultExchangeMessagesTransportKind");
	Query.SetParameter("Peer", Peer);
	Query.SetParameter("DefaultExchangeMessagesTransportKind", Enums.ExchangeMessagesTransportTypes.ExternalSystem);
	
	SetPrivilegedMode(True);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Selection.ExternalSystemConnectionParameters.Get();
	EndIf;
	
	Return Undefined;
	
EndFunction

Procedure SaveExternalSystemTransportSettings(Peer, ConnectionParameters) Export
	
	SetPrivilegedMode(True);
	
	RecordManager = CreateRecordManager();
	RecordManager.Peer = Peer;
	RecordManager.DefaultExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.ExternalSystem;
	RecordManager.ExternalSystemConnectionParameters = New ValueStorage(ConnectionParameters, New Deflation(9));
	
	RecordManager.Write(True);
	
EndProcedure

#EndRegion

#Region Private

// See SafeModeManagerOverridable.OnFillPermissionsToAccessExternalResources
Procedure OnFillPermissionsToAccessExternalResources(PermissionsRequests) Export
	
	TransportSettings = SavedTransportSettings();
	
	While TransportSettings.Next() Do
		
		QueryOptions = RequiestToUseExternalResourcesParameters();
		RequestToUseExternalResources(PermissionsRequests, TransportSettings, QueryOptions);
		
	EndDo;
	
EndProcedure

Function SavedTransportSettings()
	
	Query = New Query;
	Query.Text = "SELECT
	|	TransportSettings.Peer AS Peer,
	|	TransportSettings.FTPConnectionPath,
	|	TransportSettings.FILEDataExchangeDirectory,
	|	TransportSettings.WSWebServiceURL,
	|	TransportSettings.COMInfobaseDirectory,
	|	TransportSettings.COM1CEnterpriseServerSideInfobaseName,
	|	TransportSettings.FTPConnectionPath AS FTPConnectionPath,
	|	TransportSettings.FTPConnectionPort AS FTPConnectionPort,
	|	TransportSettings.WSWebServiceURL AS WSWebServiceURL,
	|	TransportSettings.FILEDataExchangeDirectory AS FILEDataExchangeDirectory
	|FROM
	|	InformationRegister.DataExchangeTransportSettings AS TransportSettings";
	
	QueryResult = Query.Execute();
	
	Return QueryResult.Select();
	
EndFunction

Function RequiestToUseExternalResourcesParameters() Export
	
	Parameters = New Structure;
	Parameters.Insert("RequestCOM",  True);
	Parameters.Insert("RequestFILE", True);
	Parameters.Insert("RequestWS",   True);
	Parameters.Insert("RequestFTP",  True);
	
	Return Parameters;
	
EndFunction

Procedure RequestToUseExternalResources(PermissionsRequests, Record, QueryOptions) Export
	
	Permissions = New Array;
	
	ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	
	If QueryOptions.RequestFTP And Not IsBlankString(Record.FTPConnectionPath) Then
		
		AddressStructure1 = CommonClientServer.URIStructure(Record.FTPConnectionPath);
		Permissions.Add(ModuleSafeModeManager.PermissionToUseInternetResource(
			AddressStructure1.Schema, AddressStructure1.Host, Record.FTPConnectionPort));
		
	EndIf;
	
	If QueryOptions.RequestFILE And Not IsBlankString(Record.FILEDataExchangeDirectory) Then
		
		Permissions.Add(ModuleSafeModeManager.PermissionToUseFileSystemDirectory(
			Record.FILEDataExchangeDirectory, True, True));
		
	EndIf;
	
	If QueryOptions.RequestWS And Not IsBlankString(Record.WSWebServiceURL) Then
		
		AddressStructure1 = CommonClientServer.URIStructure(Record.WSWebServiceURL);
		If ValueIsFilled(AddressStructure1.Schema) Then
			Permissions.Add(ModuleSafeModeManager.PermissionToUseInternetResource(
				AddressStructure1.Schema, AddressStructure1.Host, AddressStructure1.Port));
		EndIf;
		
	EndIf;
	
	If QueryOptions.RequestCOM And (Not IsBlankString(Record.COMInfobaseDirectory)
		Or Not IsBlankString(Record.COM1CEnterpriseServerSideInfobaseName)) Then
		
		COMConnectorName = CommonClientServer.COMConnectorName();
		Permissions.Add(ModuleSafeModeManager.PermissionToCreateCOMClass(
			COMConnectorName, Common.COMConnectorID(COMConnectorName)));
		
	EndIf;
	
	// Permissions to perform synchronization by email are requested in the Email operations subsystem.
	
	If Permissions.Count() > 0 Then
		
		PermissionsRequests.Add(
			ModuleSafeModeManager.RequestToUseExternalResources(Permissions, Record.Peer));
		
	EndIf;
	
EndProcedure

Procedure WritePassword(PasswordNameInStructure, PasswordNameOnWrite, RecordStructure)
	
	If RecordStructure.Property(PasswordNameInStructure) Then
		SetPrivilegedMode(True);
		Common.WriteDataToSecureStorage(RecordStructure.Peer, RecordStructure[PasswordNameInStructure], PasswordNameOnWrite);
		SetPrivilegedMode(False);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// The functions of receiving setting values for exchange plan node.

// Retrieves settings of the specified transport kind.
// If the transport kind is not specified (ExchangeTransportKind = Undefined),
// it receives settings of all transport kinds existing in the system.
//
Function TransportSettings(Val Peer, Val ExchangeTransportKind = Undefined) Export
	
	SetPrivilegedMode(True);
	
	RecordManager = CreateRecordManager();
	RecordManager.Peer = Peer;
	RecordManager.Read();
	
	If RecordManager.Selected() Then
		Return ExchangeTransportSettings(Peer, ExchangeTransportKind);
	ElsIf Common.DataSeparationEnabled()
		And Common.SeparatedDataUsageAvailable()
		And Common.SubsystemExists("StandardSubsystems.SaaSOperations.DataExchangeSaaS") Then
		
		DataAreaExchangeTransportConfigurationModule = Common.CommonModule("InformationRegisters.DataAreaExchangeTransportSettings");
		Return DataAreaExchangeTransportConfigurationModule.TransportSettings(Peer);
		
	EndIf;
	
	Return ExchangeTransportSettings(Peer, ExchangeTransportKind);
	
EndFunction

Function DefaultExchangeMessagesTransportKind(Peer) Export
	
	SetPrivilegedMode(True);
	
	// Function return value.
	MessagesTransportKind = Undefined;
	
	Query = New Query(
	"SELECT
	|	TransportSettings.DefaultExchangeMessagesTransportKind AS DefaultExchangeMessagesTransportKind
	|FROM
	|	InformationRegister.DataExchangeTransportSettings AS TransportSettings
	|WHERE
	|	TransportSettings.Peer = &Peer");
	Query.SetParameter("Peer", Peer);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		MessagesTransportKind = Selection.DefaultExchangeMessagesTransportKind;
	EndIf;
	
	If MessagesTransportKind = Undefined
		And Common.DataSeparationEnabled()
		And Common.SeparatedDataUsageAvailable()
		And Common.SubsystemExists("StandardSubsystems.SaaSOperations.DataExchangeSaaS") Then
		
		ModuleForConfiguringDataAreaExchangeTransport = Common.CommonModule("InformationRegisters.DataAreasExchangeTransportSettings");
		MessagesTransportKind = ModuleForConfiguringDataAreaExchangeTransport.DefaultExchangeMessagesTransportKind(Peer);
		
	EndIf;
	
	Return MessagesTransportKind;
	
EndFunction

Function DataExchangeDirectoryName(ExchangeMessagesTransportKind, InfobaseNode) Export
	
	// Function return value.
	Result = "";
	
	If ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.FILE Then
		
		TransportSettings = TransportSettings(InfobaseNode);
		
		Result = TransportSettings["FILEDataExchangeDirectory"];
		
	ElsIf ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.FTP Then
		
		TransportSettings = TransportSettings(InfobaseNode);
		
		Result = TransportSettings["FTPConnectionPath"];
		
	EndIf;
	
	Return Result;
EndFunction

Function ConfiguredTransportTypes(InfobaseNode) Export
	
	Result = New Array;
	
	TransportSettings = TransportSettings(InfobaseNode);
	
	If Common.DataSeparationEnabled()
		And Common.SeparatedDataUsageAvailable() Then
		
		If Not TransportSettings = Undefined Then
			If ValueIsFilled(TransportSettings.FILEDataExchangeDirectory) Then
				Result.Add(Enums.ExchangeMessagesTransportTypes.FILE);
			EndIf;
			
			If ValueIsFilled(TransportSettings.FTPConnectionPath) Then
				Result.Add(Enums.ExchangeMessagesTransportTypes.FTP);
			EndIf;
		EndIf;
		
	Else
		If ValueIsFilled(TransportSettings.COMInfobaseDirectory) 
			Or ValueIsFilled(TransportSettings.COM1CEnterpriseServerSideInfobaseName) Then
			Result.Add(Enums.ExchangeMessagesTransportTypes.COM);
		EndIf;
		
		If ValueIsFilled(TransportSettings.EMAILAccount) Then
			Result.Add(Enums.ExchangeMessagesTransportTypes.EMAIL);
		EndIf;
		
		If ValueIsFilled(TransportSettings.FILEDataExchangeDirectory) Then
			Result.Add(Enums.ExchangeMessagesTransportTypes.FILE);
		EndIf;
		
		If ValueIsFilled(TransportSettings.FTPConnectionPath) Then
			Result.Add(Enums.ExchangeMessagesTransportTypes.FTP);
		EndIf;
		
		If ValueIsFilled(TransportSettings.WSWebServiceURL) Then
			Result.Add(Enums.ExchangeMessagesTransportTypes.WS);
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions.

// Retrieves settings of the specified transport kind.
// If the transport kind is not specified (ExchangeTransportKind = Undefined),
// it receives settings of all transport kinds existing in the system.
//
// Parameters:
//  No.
// 
// Returns:
//  
//
Function ExchangeTransportSettings(Peer, ExchangeTransportKind)
	
	SettingsStructure = New Structure;
	
	// 
	SettingsStructure.Insert("DefaultExchangeMessagesTransportKind");
	PasswordsList = "ArchivePasswordExchangeMessages";
	
	If ExchangeTransportKind = Undefined Then
		PasswordsList = PasswordsList + ",FTPConnectionPassword,WSPassword,COMUserPassword";
		For Each TransportKind In Enums.ExchangeMessagesTransportTypes Do
			
			TransportSettingsStructure = ExchangeTransportSettingsContent(Common.EnumerationValueName(TransportKind));
			
			SettingsStructure = MergeCollections(SettingsStructure, TransportSettingsStructure);
			
		EndDo;
		
	Else
		
		TransportSettingsStructure = ExchangeTransportSettingsContent(Common.EnumerationValueName(ExchangeTransportKind));
		SettingsStructure = MergeCollections(SettingsStructure, TransportSettingsStructure);
		
		If ExchangeTransportKind = Enums.ExchangeMessagesTransportTypes.COM Then
			PasswordsList = PasswordsList + ",COMUserPassword";
		ElsIf ExchangeTransportKind = Enums.ExchangeMessagesTransportTypes.WS Then
			PasswordsList = PasswordsList + ",WSPassword";
		ElsIf ExchangeTransportKind = Enums.ExchangeMessagesTransportTypes.FTP Then
			PasswordsList = PasswordsList + ",FTPConnectionPassword";
		EndIf;
	EndIf;
	
	Result = GetRegisterDataByStructure(Peer, SettingsStructure);
	Result.Insert("UseTempDirectoryToSendAndReceiveMessages", True);
	
	SetPrivilegedMode(True);
	Passwords = Common.ReadDataFromSecureStorage(Peer, PasswordsList);
	SetPrivilegedMode(False);
	
	If TypeOf(Passwords) = Type("Structure") Then
		For Each KeyAndValue In Passwords Do
			Result.Insert(KeyAndValue.Key, KeyAndValue.Value);
		EndDo;
	Else
		Result.Insert(PasswordsList, Passwords);
	EndIf;
	
	Result.Insert("SourceInfobaseID", "");
	
	Return Result;
EndFunction

Function GetRegisterDataByStructure(Peer, SettingsStructure)
	
	If Not ValueIsFilled(Peer) Then
		Return SettingsStructure;
	EndIf;
	
	If SettingsStructure.Count() = 0 Then
		Return SettingsStructure;
	EndIf;
	
	// 
	// 
	SelectedFields = "";
	For Each SettingItem In SettingsStructure Do
		
		SelectedFields = SelectedFields + SettingItem.Key + ", ";
		
	EndDo;
	
	// 
	StringFunctionsClientServer.DeleteLastCharInString(SelectedFields, 2);
	
	QueryTextTemplate2 = 
	"SELECT
	|	&SelectedFields
	|FROM
	|	InformationRegister.DataExchangeTransportSettings AS TransportSettings
	|WHERE
	|	TransportSettings.Peer = &Peer";
	
	QueryText = StrReplace(QueryTextTemplate2, "&SelectedFields", SelectedFields);
	
	Query = New Query(QueryText);
	Query.SetParameter("Peer", Peer);
	Selection = Query.Execute().Select();
	
	// Filling the structure if settings for the node are filled.
	If Selection.Next() Then
		
		For Each SettingItem In SettingsStructure Do
			
			SettingsStructure[SettingItem.Key] = Selection[SettingItem.Key];
			
		EndDo;
		
	EndIf;
	
	Return SettingsStructure;
	
EndFunction

Function ExchangeTransportSettingsContent(SearchSubstring)
	
	TransportSettingsStructure = New Structure;
	
	RecordSet = CreateRecordSet();
	Record = RecordSet.Add(); // 
	
	For Each Resource In RecordSet.Metadata().Resources Do
		
		If StrFind(Resource.Name, SearchSubstring) <> 0 Then
			
			TransportSettingsStructure.Insert(Resource.Name, Record[Resource.Name]);
			
		EndIf;
		
	EndDo;
	
	Return TransportSettingsStructure;
	
EndFunction

Function MergeCollections(Structure1, Structure2)
	
	ResultingStructure = New Structure;
	
	SupplementCollection(Structure1, ResultingStructure);
	SupplementCollection(Structure2, ResultingStructure);
	
	Return ResultingStructure;
EndFunction

Procedure SupplementCollection(Source, Receiver)
	
	For Each Item In Source Do
		
		Receiver.Insert(Item.Key, Item.Value);
		
	EndDo;
	
EndProcedure

#Region UpdateHandlers

Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	AdditionalParameters = InfobaseUpdate.AdditionalProcessingMarkParameters();
	AdditionalParameters.IsIndependentInformationRegister = True;
	AdditionalParameters.FullRegisterName             = "InformationRegister.DeleteExchangeTransportSettings";
	
	QueryOptions = New Structure;
	QueryOptions.Insert("ExchangePlansArray1",                 New Array);
	QueryOptions.Insert("AdditionalExchangePlanProperties", "");
	QueryOptions.Insert("ResultToTemporaryTable",       True);
	
	TempTablesManager = New TempTablesManager;
	
	ExchangeNodesQuery = New Query(DataExchangeServer.ExchangePlansForMonitorQueryText(QueryOptions, False));
	ExchangeNodesQuery.TempTablesManager = TempTablesManager;
	ExchangeNodesQuery.Execute();
	
	Query = New Query(
	"SELECT
	|	TransportSettings.InfobaseNode AS InfobaseNode
	|FROM
	|	ConfigurationExchangePlans AS ConfigurationExchangePlans
	|		INNER JOIN InformationRegister.DeleteExchangeTransportSettings AS TransportSettings
	|		ON (TransportSettings.InfobaseNode = ConfigurationExchangePlans.InfobaseNode)");
	
	Query.TempTablesManager = TempTablesManager;
	
	Result = Query.Execute().Unload();
	
	InfobaseUpdate.MarkForProcessing(Parameters, Result, AdditionalParameters);
	
EndProcedure

Procedure ProcessDataForMigrationToNewVersion(Parameters) Export
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	ProcessingCompleted = True;
	
	RegisterMetadata    = Metadata.InformationRegisters.DeleteExchangeTransportSettings;
	FullRegisterName     = RegisterMetadata.FullName();
	RegisterPresentation = RegisterMetadata.Presentation();
	
	AdditionalProcessingDataSelectionParameters = InfobaseUpdate.AdditionalProcessingDataSelectionParameters();
	
	Selection = InfobaseUpdate.SelectStandaloneInformationRegisterDimensionsToProcess(
		Parameters.Queue, FullRegisterName, AdditionalProcessingDataSelectionParameters);
	
	Processed = 0;
	RecordsWithIssuesCount = 0;
	
	While Selection.Next() Do
		RepresentationOfTheReference = String(Selection.InfobaseNode);
		Try
			
			TransferSettingsOfCorrespondentDataExchangeTransport(Selection.InfobaseNode);
			Processed = Processed + 1;
			
		Except
			
			RecordsWithIssuesCount = RecordsWithIssuesCount + 1;
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Couldn''t process a set of ""%1"" register records with filter ""InfobaseNode = %2"" due to:
				|%3';"), RegisterPresentation, RepresentationOfTheReference,
				ErrorProcessing.DetailErrorDescription(ErrorInfo()));
				
			WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Warning,
				RegisterMetadata, , MessageText);
			
		EndTry;
		
	EndDo;
	
	If Not InfobaseUpdate.DataProcessingCompleted(Parameters.Queue, FullRegisterName) Then
		ProcessingCompleted = False;
	EndIf;
	
	If Processed = 0 And RecordsWithIssuesCount <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Procedure InformationRegisters.DataExchangeTransportSettings.ProcessDataForMigrationToNewVersion failed to process (skipped) some exchange node records: %1';"), 
			RecordsWithIssuesCount);
		Raise MessageText;
	Else
		WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Information,
			, ,
			StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The InformationRegisters.DataExchangeTransportSettings.ProcessDataForMigrationToNewVersion procedure processed records: %1';"),
			Processed));
	EndIf;
	
	Parameters.ProcessingCompleted = ProcessingCompleted;
	
EndProcedure

Procedure TransferSettingsOfCorrespondentDataExchangeTransport(InfobaseNode) Export
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(InfobaseNode) Then
		RecordSet = InformationRegisters.DeleteExchangeTransportSettings.CreateRecordSet();
		RecordSet.Filter.InfobaseNode.Set(InfobaseNode);
		
		InfobaseUpdate.MarkProcessingCompletion(RecordSet);
		Return;
	EndIf;
	
	BeginTransaction();
	Try
		Block = New DataLock;
		
		LockItem = Block.Add("InformationRegister.DeleteExchangeTransportSettings");
		LockItem.SetValue("InfobaseNode", InfobaseNode);
		
		LockItem = Block.Add("InformationRegister.DataExchangeTransportSettings");
		LockItem.SetValue("Peer", InfobaseNode);
		
		Block.Lock();
		
		RecordSetOld = InformationRegisters.DeleteExchangeTransportSettings.CreateRecordSet();
		RecordSetOld.Filter.InfobaseNode.Set(InfobaseNode);
		
		RecordSetOld.Read();
		
		If RecordSetOld.Count() = 0 Then
			InfobaseUpdate.MarkProcessingCompletion(RecordSetOld);
		Else
			RecordSetNew = CreateRecordSet();
			RecordSetNew.Filter.Peer.Set(InfobaseNode);
			
			Record_New = RecordSetNew.Add();
			FillPropertyValues(Record_New, RecordSetOld[0]);
			Record_New.Peer = InfobaseNode;
			
			InfobaseUpdate.WriteRecordSet(RecordSetNew);
			
			RecordSetOld.Clear();
			InfobaseUpdate.WriteRecordSet(RecordSetOld);
		EndIf;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

#EndRegion

#EndRegion

#EndIf