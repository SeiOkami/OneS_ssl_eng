///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region EventHandlersForm

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
		
	FillAvailableTransportKinds();
	
	EstablishWebServiceConnectionEventLogEvent =
		DataExchangeWebService.EstablishWebServiceConnectionEventLogEvent();
	
	If Common.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		Items.InternetAccessParameters.Visible = True;
		Items.InternetAccessParametersFTP.Visible = True;
	Else
		Items.InternetAccessParameters.Visible = False;
		Items.InternetAccessParametersFTP.Visible = False;
	EndIf;
	
	If ValueIsFilled(Record.Peer) Then
		FormPasswords = "COMUserPassword,FTPConnectionPassword,WSPassword,ArchivePasswordExchangeMessages";
		
		SetPrivilegedMode(True);
		Passwords = Common.ReadDataFromSecureStorage(Record.Peer, FormPasswords);
		SetPrivilegedMode(False);
		
		For Each FormPassword In StrSplit(FormPasswords, ",", False) Do
			ThisObject[FormPassword] = ?(ValueIsFilled(Passwords[FormPassword]), ThisObject.UUID, "");
		EndDo;
	EndIf;
	
	If Common.DataSeparationEnabled() Then
		
		If ValueIsFilled(Record.WSCorrespondentEndpoint) Then		
			Items.WSWebServiceURL.Visible = False;
			Items.WSUserAndPassword.Visible = False;
			Items.InternetAccessParameters.Visible = False;
			
			SetPrivilegedMode(True);
			WSCorrespondentEndpoint = String(Record.WSCorrespondentEndpoint);
			SetPrivilegedMode(True);
		Else
			Items.WSCorrespondentEndpoint.Visible = False;
			Items.WSCorrespondentDataArea.Visible = False;
		EndIf;
		
		Items.TestWSConnection.Visible = False;
		Items.WSCorrespondentDataArea.ReadOnly = Not Users.IsFullUser(, True);
		
	Else	
						
		Items.WSCorrespondentEndpoint.Visible = False;
		Items.WSCorrespondentDataArea.Visible = False;

	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetTransportKindsTabsDisplay();
	
	InfobaseOperatingModeOnChange();
	
	OSAuthenticationOnChange();
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If WriteParameters.Property("ExternalResourcesAllowed") Then
		Return;
	EndIf;
	
	Cancel = True;
	
	ClosingNotification1 = New NotifyDescription("AllowExternalResourceCompletion", ThisObject, WriteParameters);
	If StandardSubsystemsClient.ApplicationStartCompleted()
		And CommonClient.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		Queries = CreateRequestToUseExternalResources(Record, True, True, True, True);
		ModuleSafeModeManagerClient = CommonClient.CommonModule("SafeModeManagerClient");
		ModuleSafeModeManagerClient.ApplyExternalResourceRequests(Queries, ThisObject, ClosingNotification1);
	Else
		ExecuteNotifyProcessing(ClosingNotification1, DialogReturnCode.OK);
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	If WriteParameters.Property("WriteAndClose") Then
		Close();
	EndIf;
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	SetPrivilegedMode(True);
	If COMUserPasswordChanged Then
		Common.WriteDataToSecureStorage(CurrentObject.Peer, COMUserPassword, "COMUserPassword")
	EndIf;
	If FTPConnectionPasswordChanged Then
		Common.WriteDataToSecureStorage(CurrentObject.Peer, FTPConnectionPassword, "FTPConnectionPassword")
	EndIf;
	If WSPasswordChanged Then
		Common.WriteDataToSecureStorage(CurrentObject.Peer, WSPassword, "WSPassword")
	EndIf;
	If ExchangeMessageArchivePasswordChanged Then
		Common.WriteDataToSecureStorage(CurrentObject.Peer, ArchivePasswordExchangeMessages, "ArchivePasswordExchangeMessages")
	EndIf;
	SetPrivilegedMode(False);
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FILEInformationExchangeDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	
	DataExchangeClient.FileDirectoryChoiceHandler(Record, "FILEDataExchangeDirectory", StandardProcessing);
	
EndProcedure

&AtClient
Procedure FILEInformationExchangeDirectoryOpening(Item, StandardProcessing)
	
	DataExchangeClient.FileOrDirectoryOpenHandler(Record, "FILEDataExchangeDirectory", StandardProcessing)
	
EndProcedure

&AtClient
Procedure COMInfobaseDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	
	DataExchangeClient.FileDirectoryChoiceHandler(Record, "COMInfobaseDirectory", StandardProcessing);
	
EndProcedure

&AtClient
Procedure COMInfobaseDirectoryOpening(Item, StandardProcessing)

DataExchangeClient.FileOrDirectoryOpenHandler(Record, "COMInfobaseDirectory", StandardProcessing)

EndProcedure

&AtClient
Procedure COMInfobaseOperatingModeOnChange(Item)
	
	InfobaseOperatingModeOnChange();
	
EndProcedure

&AtClient
Procedure COMOSAuthenticationOnChange(Item)
	
	OSAuthenticationOnChange();
	
EndProcedure

&AtClient
Procedure WSPasswordOnChange(Item)
	WSPasswordChanged = True;
EndProcedure

&AtClient
Procedure ArchivePasswordExchangeMessages1OnChange(Item)
	ExchangeMessageArchivePasswordChanged = True;
EndProcedure

&AtClient
Procedure FTPConnectionPasswordOnChange(Item)
	FTPConnectionPasswordChanged = True;
EndProcedure

&AtClient
Procedure ArchivePasswordExchangeMessagesOnChange(Item)
	ExchangeMessageArchivePasswordChanged = True;
EndProcedure

&AtClient
Procedure ArchivePasswordExchangeMessages2OnChange(Item)
	ExchangeMessageArchivePasswordChanged = True;
EndProcedure

&AtClient
Procedure COMUserPasswordOnChange(Item)
	COMUserPasswordChanged = True;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure TestCOMConnection(Command)
	
	ClosingNotification1 = New NotifyDescription("TestCOMConnectionCompletion", ThisObject);
	If CommonClient.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		Queries = CreateRequestToUseExternalResources(Record, True, False, False, False);
		ModuleSafeModeManagerClient = CommonClient.CommonModule("SafeModeManagerClient");
		ModuleSafeModeManagerClient.ApplyExternalResourceRequests(Queries, ThisObject, ClosingNotification1);
	Else
		ExecuteNotifyProcessing(ClosingNotification1, DialogReturnCode.OK);
	EndIf;
	
EndProcedure

&AtClient
Procedure TestWSConnection(Command)
	
	ClosingNotification1 = New NotifyDescription("TestWSConnectionCompletion", ThisObject);
	If CommonClient.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		Queries = CreateRequestToUseExternalResources(Record, False, False, True, False);
		ModuleSafeModeManagerClient = CommonClient.CommonModule("SafeModeManagerClient");
		ModuleSafeModeManagerClient.ApplyExternalResourceRequests(Queries, ThisObject, ClosingNotification1);
	Else
		ExecuteNotifyProcessing(ClosingNotification1, DialogReturnCode.OK);
	EndIf;
	
EndProcedure

&AtClient
Procedure TestFILEConnection(Command)
	
	ClosingNotification1 = New NotifyDescription("TestFILEConnectionCompletion", ThisObject);
	If CommonClient.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		Queries = CreateRequestToUseExternalResources(Record, False, True, False, False);
		ModuleSafeModeManagerClient = CommonClient.CommonModule("SafeModeManagerClient");
		ModuleSafeModeManagerClient.ApplyExternalResourceRequests(Queries, ThisObject, ClosingNotification1);
	Else
		ExecuteNotifyProcessing(ClosingNotification1, DialogReturnCode.OK);
	EndIf;
	
EndProcedure

&AtClient
Procedure TestFTPConnection(Command)
	
	ClosingNotification1 = New NotifyDescription("TestFTPConnectionCompletion", ThisObject);
	If CommonClient.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		Queries = CreateRequestToUseExternalResources(Record, False, False, False, True);
		ModuleSafeModeManagerClient = CommonClient.CommonModule("SafeModeManagerClient");
		ModuleSafeModeManagerClient.ApplyExternalResourceRequests(Queries, ThisObject, ClosingNotification1);
	Else
		ExecuteNotifyProcessing(ClosingNotification1, DialogReturnCode.OK);
	EndIf;
	
EndProcedure

&AtClient
Procedure TestEMAILConnection(Command)
	
	TestConnection("EMAIL");
	
EndProcedure

&AtClient
Procedure InternetAccessParameters(Command)
	
	DataExchangeClient.OpenProxyServerParametersForm();
	
EndProcedure

&AtClient
Procedure WriteAndClose(Command)
	
	WriteParameters = New Structure;
	WriteParameters.Insert("WriteAndClose");
	Write(WriteParameters);

EndProcedure


#EndRegion

#Region Private

&AtClient
Procedure TestConnection(TransportKindAsString, NewPassword = Undefined)
	
	Cancel = False;
	
	ClearMessages();
	
	TestConnectionAtServer(Cancel, TransportKindAsString, NewPassword);
	
	NotifyUserAboutConnectionResult(Cancel);
	
EndProcedure

&AtServer
Procedure TestConnectionAtServer(Cancel, TransportKindAsString, NewPassword)
	
	ErrorMessage = "";
		
	PasswordsToCheck = Undefined;
	
	AddPasswordToCheck(PasswordsToCheck, "COMUserPassword", COMUserPasswordChanged);
	AddPasswordToCheck(PasswordsToCheck, "FTPConnectionPassword", FTPConnectionPasswordChanged);
	AddPasswordToCheck(PasswordsToCheck, "WSPassword", WSPasswordChanged);
	AddPasswordToCheck(PasswordsToCheck, "ArchivePasswordExchangeMessages", ExchangeMessageArchivePasswordChanged);
	
	DataExchangeServer.CheckExchangeMessageTransportDataProcessorAttachment(Cancel, Record,
		Enums.ExchangeMessagesTransportTypes[TransportKindAsString], ErrorMessage, PasswordsToCheck);
		
	If Cancel Then
		Common.MessageToUser(ErrorMessage, , , , Cancel);
	EndIf;
	
EndProcedure

&AtServer
Procedure AddPasswordToCheck(Passwords, PasswordKind, PasswordChanged)
	
	If PasswordChanged Then
		If Passwords = Undefined Then
			Passwords = New Structure;
		EndIf;
		
		Passwords.Insert(PasswordKind, ThisObject[PasswordKind]);
	EndIf;
	
EndProcedure

&AtServer
Procedure ExecuteExternalConnectionTest(Cancel)
	
	ConnectionParameters = New Structure;
	ConnectionParameters.Insert("COMInfobaseOperatingMode", Record.COMInfobaseOperatingMode);
	ConnectionParameters.Insert("COMOperatingSystemAuthentication", Record.COMOperatingSystemAuthentication);
	ConnectionParameters.Insert("COM1CEnterpriseServerSideInfobaseName",
		Record.COM1CEnterpriseServerSideInfobaseName);
	ConnectionParameters.Insert("COMUserName", Record.COMUserName);
	ConnectionParameters.Insert("COM1CEnterpriseServerName", Record.COM1CEnterpriseServerName);
	ConnectionParameters.Insert("COMInfobaseDirectory", Record.COMInfobaseDirectory);
	
	If Not COMUserPasswordChanged Then
		
		SetPrivilegedMode(True);
		ConnectionParameters.Insert("COMUserPassword",
			Common.ReadDataFromSecureStorage(Record.Peer, "COMUserPassword"));
		SetPrivilegedMode(False);
		
	Else
		
		ConnectionParameters.Insert("COMUserPassword", COMUserPassword);
		
	EndIf;
	
	// Attempting to establish external connection.
	Result = DataExchangeServer.EstablishExternalConnectionWithInfobase(ConnectionParameters);
	// Displaying error message.
	If Result.Join = Undefined Then
		Common.MessageToUser(Result.BriefErrorDetails, , , , Cancel);
	EndIf;
	
EndProcedure

&AtServer
Procedure TestWSConnectionEstablished(Cancel)
	
	ConnectionParameters = DataExchangeServer.WSParameterStructure();
	FillPropertyValues(ConnectionParameters, Record);
	
	If Not WSPasswordChanged Then
		
		SetPrivilegedMode(True);
		ConnectionParameters.WSPassword = Common.ReadDataFromSecureStorage(Record.Peer, "WSPassword");
		SetPrivilegedMode(False);
		
	Else
		
		ConnectionParameters.WSPassword = WSPassword;
		
	EndIf;
	
	UserMessage = "";
	If Not DataExchangeWebService.CorrespondentConnectionEstablished(Record.Peer, ConnectionParameters, UserMessage) Then
		Common.MessageToUser(UserMessage,,,, Cancel);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillAvailableTransportKinds()
	
	AvailableTransportKinds.Clear();
	Items.DefaultExchangeMessagesTransportKind.ChoiceList.Clear();
	
	UsedTransports = New Array;
	
	If Common.DataSeparationEnabled() Then
		
		If Record.DefaultExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.WS
			Or Record.DefaultExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.WSPassiveMode Then
			
			UsedTransports.Add(Record.DefaultExchangeMessagesTransportKind);	
			
		Else
			
			ExceptionText = NStr("en = 'Message transport setup in SaaS mode is only relevant for synchronizations that use web services';");
			Raise ExceptionText;
			
		EndIf;
		
	ElsIf ValueIsFilled(Record.Peer) Then
		
		UsedTransports = DataExchangeCached.UsedExchangeMessagesTransports(Record.Peer);
		
		If ValueIsFilled(Record.DefaultExchangeMessagesTransportKind)
			And UsedTransports.Find(Record.DefaultExchangeMessagesTransportKind) = Undefined Then
			UsedTransports.Add(Record.DefaultExchangeMessagesTransportKind);
		EndIf;
		
	EndIf;
	
	TypesOfTransportAndFormElements = New Map();
	TypesOfTransportAndFormElements.Insert(Enums.ExchangeMessagesTransportTypes.EMAIL,				Items.EMAILTransportSettings.Name);
	TypesOfTransportAndFormElements.Insert(Enums.ExchangeMessagesTransportTypes.FILE,				Items.FILETransportSettings.Name);
	TypesOfTransportAndFormElements.Insert(Enums.ExchangeMessagesTransportTypes.FTP,				Items.FTPTransportSettings.Name);
	TypesOfTransportAndFormElements.Insert(Enums.ExchangeMessagesTransportTypes.WS,				Items.TransportSettingsWS.Name);
	TypesOfTransportAndFormElements.Insert(Enums.ExchangeMessagesTransportTypes.COM,				Items.COMTransportSettings.Name);
	TypesOfTransportAndFormElements.Insert(Enums.ExchangeMessagesTransportTypes.WSPassiveMode,	Items.WSTransportSettingsPassiveMode.Name);
	
	For Each Item In UsedTransports Do
				
		AvailableTransportKindsRow = AvailableTransportKinds.Add();
		AvailableTransportKindsRow.TransportKind = Item;
		AvailableTransportKindsRow.PageName   = TypesOfTransportAndFormElements.Get(Item);
		
		Items.DefaultExchangeMessagesTransportKind.ChoiceList.Add(Item, String(Item));
		
	EndDo;
	
EndProcedure

&AtClient
Procedure SetTransportKindsTabsDisplay()
	
	ItemPropertyName = "Visible";
	#If WebClient Then
		ItemPropertyName = "Enabled";
	#EndIf
	
	For Each TransportKindPage In Items.TransportKindsPages.ChildItems Do
		
		TransportKindPage[ItemPropertyName] = False;
		
	EndDo;
	
	For Each AvailableTransportKindsRow In AvailableTransportKinds Do
		
		ItemTab = Items[AvailableTransportKindsRow.PageName];
		ItemTab[ItemPropertyName] = True;
		
		If Record.DefaultExchangeMessagesTransportKind = AvailableTransportKindsRow.TransportKind Then
			Items.TransportKindsPages.CurrentPage = ItemTab;
		EndIf;
		
	EndDo;
	
	If AvailableTransportKinds.Count() = 1 Then
		
		Items.TransportKindsPages.PagesRepresentation = FormPagesRepresentation.None;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure NotifyUserAboutConnectionResult(Val AttachmentError)
	
	WarningText = ?(AttachmentError, NStr("en = 'Cannot establish connection.';"),
											   NStr("en = 'Connection established.';"));
	ShowMessageBox(, WarningText);
	
EndProcedure

&AtClient
Procedure InfobaseOperatingModeOnChange()
	
	CurrentPage = ?(Record.COMInfobaseOperatingMode = 0, Items.InfobaseFileModePage, Items.InfobaseClientServerModePage);
	
	Items.InfobaseModes.CurrentPage = CurrentPage;
	
EndProcedure

&AtClient
Procedure OSAuthenticationOnChange()
	
	Items.COMUserName.Enabled    = Not Record.COMOperatingSystemAuthentication;
	Items.COMUserPassword.Enabled = Not Record.COMOperatingSystemAuthentication;
	
EndProcedure

&AtClient
Procedure AllowExternalResourceCompletion(Result, WriteParameters) Export
	
	If Result = DialogReturnCode.OK Then
		If WriteParameters.Property("WriteAndClose") Then
			AttachIdleHandler("WriteAndCloseAfterExternalResourcesPermissionQuery", 0.1, True);
		Else
			AttachIdleHandler("WriteAfterExternalResourcesPermissionQuery", 0.1, True);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure WriteAndCloseAfterExternalResourcesPermissionQuery()
	
	WriteParameters = New Structure;
	WriteParameters.Insert("ExternalResourcesAllowed");
	WriteParameters.Insert("WriteAndClose");
	
	Write(WriteParameters);
	
EndProcedure

&AtClient
Procedure WriteAfterExternalResourcesPermissionQuery()
	
	WriteParameters = New Structure;
	WriteParameters.Insert("ExternalResourcesAllowed");
	
	Write(WriteParameters);
	
EndProcedure

&AtServerNoContext
Function CreateRequestToUseExternalResources(Val Record, RequestCOM,
	RequestFILE, RequestWS, RequestFTP)
	
	PermissionsRequests = New Array;
	
	QueryOptions = InformationRegisters.DataExchangeTransportSettings.RequiestToUseExternalResourcesParameters();
	QueryOptions.RequestCOM  = RequestCOM;
	QueryOptions.RequestFILE = RequestFILE;
	QueryOptions.RequestWS   = RequestWS;
	QueryOptions.RequestFTP  = RequestFTP;
	
	InformationRegisters.DataExchangeTransportSettings.RequestToUseExternalResources(PermissionsRequests,
		Record, QueryOptions);
		
	Return PermissionsRequests;
	
EndFunction

&AtClient
Procedure TestFILEConnectionCompletion(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.OK Then
		
		TestConnection("FILE");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure TestFTPConnectionCompletion(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.OK Then
		
		TestConnection("FTP", ?(FTPConnectionPasswordChanged, FTPConnectionPassword, Undefined));
		
	EndIf;
	
EndProcedure

&AtClient
Procedure TestWSConnectionCompletion(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.OK Then
		
		Cancel = False;
		
		ClearMessages();
		
		TestWSConnectionEstablished(Cancel);
		
		NotifyUserAboutConnectionResult(Cancel);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure TestCOMConnectionCompletion(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.OK Then
		
		ClearMessages();
		
		If CommonClient.FileInfobase() Then
			Notification = New NotifyDescription("TestCOMConnectionCompletionAfterCheckCOMConnector", ThisObject);
			CommonClient.RegisterCOMConnector(False, Notification);
		Else 
			TestCOMConnectionCompletionAfterCheckCOMConnector(True, Undefined);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure TestCOMConnectionCompletionAfterCheckCOMConnector(IsRegistered, Context) Export
	
	If IsRegistered Then 
		
		Cancel = False;
		
		ExecuteExternalConnectionTest(Cancel);
		NotifyUserAboutConnectionResult(Cancel)
		
	EndIf;
	
EndProcedure

#EndRegion
